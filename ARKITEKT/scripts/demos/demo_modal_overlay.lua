-- @noindex
-- Arkitekt/demo_modal_overlay.lua
-- Demo of the modal overlay system with chip list integration + justified layout + mode switcher


-- Auto-injected package path setup for relocated script

-- Package path setup for relocated script
local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path

-- Ensure root_path ends with a slash
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end

-- Add both module search paths
local arkitekt_path= root_path .. "ARKITEKT/"
local scripts_path = root_path .. "ARKITEKT/scripts/"
package.path = arkitekt_path.. "?.lua;" .. arkitekt_path.. "?/init.lua;" .. 
               scripts_path .. "?.lua;" .. scripts_path .. "?/init.lua;" .. 
               package.path

local script_path = debug.getinfo(1, "S").source:match("@?(.*)[\\/]") or ""
local root_path = script_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
root_path = root_path:match("(.*)[\\/][^\\/]+[\\/]?$") or root_path
if not root_path:match("[\\/]$") then root_path = root_path .. "/" end
package.path = root_path .. "?.lua;" .. root_path .. "?/init.lua;" .. package.path

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local function dirname(p) return p:match("^(.*)[/\\]") end
local function join(a,b) local s=package.config:sub(1,1); return (a:sub(-1)==s) and (a..b) or (a..s..b) end
local SRC   = debug.getinfo(1,"S").source:sub(2)
local HERE  = dirname(SRC) or "."
local PARENT= dirname(HERE or ".") or "."
local function addpath(p) if p and p~="" and not package.path:find(p,1,true) then package.path = p .. ";" .. package.path end end
addpath(join(PARENT,"?.lua")); addpath(join(PARENT,"?/init.lua"))
addpath(join(HERE,  "?.lua")); addpath(join(HERE,  "?/init.lua"))
addpath(join(HERE,  "Arkitekt/?.lua"))
addpath(join(HERE,  "Arkitekt/?/init.lua"))
addpath(join(HERE,  "Arkitekt/?/?.lua"))

local Shell = require("arkitekt.app.runtime.shell")
local Sheet = require("arkitekt.gui.widgets.overlays.overlay.sheet")
local ChipList = require("arkitekt.gui.widgets.data.chip_list")
local OverlayConfig = require("arkitekt.gui.widgets.overlays.overlay.defaults")

local style_ok, Style = pcall(require, "arkitekt.gui.style.imgui_defaults")
local Colors = require('arkitekt.core.colors')
local hexrgb = Colors.hexrgb


local demo_state = {
  search_text = "",
  selected_tags = {},
  selected_presets = {},
  counter = 0,
  preset_layout_mode = "grid",  -- "flow", "columns", "grid"
  
  tags = {
    { id = "synth", label = "Synth", color = hexrgb("#4A90E2") },
    { id = "bass", label = "Bass", color = hexrgb("#7B68EE") },
    { id = "lead", label = "Lead", color = hexrgb("#E85D75") },
    { id = "pad", label = "Pad", color = hexrgb("#50C878") },
    { id = "pluck", label = "Pluck", color = hexrgb("#F39C12") },
    { id = "ambient", label = "Ambient", color = hexrgb("#9B59B6") },
    { id = "aggressive", label = "Aggressive", color = hexrgb("#E74C3C") },
    { id = "warm", label = "Warm", color = hexrgb("#FF8C42") },
    { id = "digital", label = "Digital", color = hexrgb("#3498DB") },
    { id = "analog", label = "Analog", color = hexrgb("#D68910") },
    { id = "bright", label = "Bright", color = hexrgb("#F1C40F") },
    { id = "dark", label = "Dark", color = hexrgb("#5D4E6D") },
    { id = "melodic", label = "Melodic", color = hexrgb("#FF6B9D") },
    { id = "percussive", label = "Percussive", color = hexrgb("#95A5A6") },
    { id = "atmospheric", label = "Atmospheric", color = hexrgb("#6C5CE7") },
  },
  
  presets = {
    { id = "p1", label = "ARP Crisis Line", color = hexrgb("#E74C3C") },
    { id = "p2", label = "BL Filterjima", color = hexrgb("#3498DB") },
    { id = "p3", label = "FX Ascensor", color = hexrgb("#F39C12") },
    { id = "p4", label = "LD Blumenkranz", color = hexrgb("#50C878") },
    { id = "p5", label = "LD Counter Flute", color = hexrgb("#9B59B6") },
    { id = "p6", label = "LD FM-Kyojin", color = hexrgb("#E85D75") },
    { id = "p7", label = "MKK Megata AH", color = hexrgb("#FF6B9D") },
    { id = "p8", label = "SC Die Folter 3", color = hexrgb("#F1C40F") },
    { id = "p9", label = "PD Holroyd", color = hexrgb("#4A90E2") },
    { id = "p10", label = "LD Twiky", color = hexrgb("#7B68EE") },
    { id = "p11", label = "DR Dropkick 2", color = hexrgb("#50E3C2") },
    { id = "p12", label = "FX Insectoid", color = hexrgb("#FF8C42") },
    { id = "p13", label = "BS Verzerrt", color = hexrgb("#D68910") },
    { id = "p14", label = "SC Mawtawr 2", color = hexrgb("#6C5CE7") },
    { id = "p15", label = "LD Ocean 2", color = hexrgb("#3498DB") },
    { id = "p16", label = "BL Liquid Bells", color = hexrgb("#4ECDC4") },
    { id = "p17", label = "FX Dialies", color = hexrgb("#E74C3C") },
    { id = "p18", label = "LD Hush Strings", color = hexrgb("#9B59B6") },
    { id = "p19", label = "SC Portal", color = hexrgb("#FF6B9D") },
    { id = "p20", label = "BL Miyajima R1", color = hexrgb("#50C878") },
    { id = "p21", label = "DR Noise Hit", color = hexrgb("#95A5A6") },
    { id = "p22", label = "FX Yimir Origin", color = hexrgb("#F39C12") },
    { id = "p23", label = "LD D91M", color = hexrgb("#7B68EE") },
    { id = "p24", label = "SC Cubic", color = hexrgb("#4A90E2") },
    { id = "p25", label = "PD A-R 0", color = hexrgb("#E85D75") },
    { id = "p26", label = "BL Spacemind", color = hexrgb("#6C5CE7") },
    { id = "p27", label = "LD Submarine", color = hexrgb("#3498DB") },
    { id = "p28", label = "SC Unromantic", color = hexrgb("#D68910") },
    { id = "p29", label = "FX NSEG2", color = hexrgb("#FF8C42") },
    { id = "p30", label = "DR Mismash", color = hexrgb("#95A5A6") },
    { id = "p31", label = "LD S3Bells", color = hexrgb("#50E3C2") },
    { id = "p32", label = "BFX Crusher55", color = hexrgb("#E74C3C") },
    { id = "p33", label = "MKK Portal", color = hexrgb("#F1C40F") },
    { id = "p34", label = "LD Kyojin 0.1", color = hexrgb("#9B59B6") },
    { id = "p35", label = "SC Die Folter", color = hexrgb("#FF6B9D") },
    { id = "p36", label = "PD Rectify", color = hexrgb("#4A90E2") },
    { id = "p37", label = "BS Jimoya", color = hexrgb("#50C878") },
    { id = "p38", label = "FX Formattic", color = hexrgb("#7B68EE") },
    { id = "p39", label = "LD Megata Soft", color = hexrgb("#E85D75") },
    { id = "p40", label = "DR Dropkick", color = hexrgb("#6C5CE7") },
  },
}

local function create_tag_selector_modal(window)
  window.overlay:push({
    id = 'tag-selector',
    close_on_scrim = true,
    esc_to_close = true,
    render = function(ctx, alpha, bounds)
      Sheet.render(ctx, alpha, bounds, function(ctx, w, h, a)
        local padding_h = 16
        
        ImGui.SetCursorPos(ctx, padding_h, 16)
        ImGui.Text(ctx, "Filter by Tags:")
        ImGui.SetCursorPosX(ctx, padding_h)
        ImGui.SetNextItemWidth(ctx, w - padding_h * 2)
        local changed, text = ImGui.InputTextWithHint(ctx, "##search", "Search tags...", demo_state.search_text)
        if changed then 
          demo_state.search_text = text 
        end
        
        ImGui.Dummy(ctx, 0, 12)
        ImGui.SetCursorPosX(ctx, padding_h)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 12)
        
        ImGui.SetCursorPosX(ctx, padding_h)
        local clicked_tag = ChipList.draw(ctx, demo_state.tags, {
          max_width = w - padding_h * 2,
          selected_ids = demo_state.selected_tags,
          search_text = demo_state.search_text,
          chip_spacing = 10,
          line_spacing = 10,
          justified = true,
          max_stretch_ratio = 1.3,
        })
        
        if clicked_tag then
          demo_state.selected_tags[clicked_tag] = not demo_state.selected_tags[clicked_tag]
        end
        
        ImGui.Dummy(ctx, 0, 20)
        ImGui.SetCursorPosX(ctx, padding_h)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 12)
        
        local button_w = 100
        local spacing = 12
        local total_w = (button_w * 2) + spacing
        local start_x = (w - total_w) * 0.5
        
        ImGui.SetCursorPosX(ctx, start_x)
        if ImGui.Button(ctx, "Apply", button_w, 32) then
          window.overlay:pop('tag-selector')
        end
        
        ImGui.SameLine(ctx)
        ImGui.Dummy(ctx, spacing, 0)
        ImGui.SameLine(ctx)
        
        if ImGui.Button(ctx, "Clear All", button_w, 32) then
          demo_state.selected_tags = {}
          window.overlay:pop('tag-selector')
        end
      end, { 
        title = "Select Tags", 
        width = 0.55, 
        height = 0.65 
      })
    end
  })
end

local function create_preset_browser_modal(window)
  window.overlay:push({
    id = 'preset-browser',
    close_on_scrim = true,
    esc_to_close = true,
    render = function(ctx, alpha, bounds)
      local custom_config = {
        sheet = {
          background = { color = hexrgb("#1E1E28") },
          header = {
            text_color = hexrgb("#50C878"),
            divider_color = hexrgb("#50C878"),
            highlight_color = hexrgb("#50C878"),
          }
        }
      }
      
      Sheet.render(ctx, alpha, bounds, function(ctx, w, h, a)
        local padding_h = 16
        
        ImGui.SetCursorPos(ctx, padding_h, 16)
        ImGui.Text(ctx, "Browse Presets:")
        ImGui.SetCursorPosX(ctx, padding_h)
        ImGui.SetNextItemWidth(ctx, w - padding_h * 2)
        local changed, text = ImGui.InputTextWithHint(ctx, "##preset_search", "Search presets...", demo_state.search_text)
        if changed then 
          demo_state.search_text = text 
        end
        
        ImGui.Dummy(ctx, 0, 12)
        ImGui.SetCursorPosX(ctx, padding_h)
        
        ImGui.Text(ctx, "Layout:")
        ImGui.SameLine(ctx, 0, 10)
        
        local modes = {"flow", "columns", "grid"}
        local mode_labels = {flow = "Flow", columns = "Columns", grid = "Grid"}
        
        for i, mode in ipairs(modes) do
          if i > 1 then
            ImGui.SameLine(ctx, 0, 6)
          end
          
          local is_active = (demo_state.preset_layout_mode == mode)
          if is_active then
            ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#50C878"))
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#60D888"))
            ImGui.PushStyleColor(ctx, ImGui.Col_ButtonActive, hexrgb("#40B868"))
          end
          
          if ImGui.Button(ctx, mode_labels[mode] .. "##mode", 80, 24) then
            demo_state.preset_layout_mode = mode
          end
          
          if is_active then
            ImGui.PopStyleColor(ctx, 3)
          end
        end
        
        ImGui.Dummy(ctx, 0, 12)
        ImGui.SetCursorPosX(ctx, padding_h)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 12)
        
        ImGui.SetCursorPosX(ctx, padding_h)
        
        local clicked_preset = nil
        
        if demo_state.preset_layout_mode == "grid" then
          clicked_preset = ChipList.draw_grid(ctx, demo_state.presets, {
            width = w - padding_h * 2,
            selected_ids = demo_state.selected_presets,
            search_text = demo_state.search_text,
            gap = 3,
            use_dot_style = true,
            bg_color = hexrgb("#252530"),
            dot_size = 7,
            dot_spacing = 7,
            rounding = 5,
            padding_h = 12,
            justified = true,
            max_stretch_ratio = 1.4,
          })
        elseif demo_state.preset_layout_mode == "columns" then
          clicked_preset = ChipList.draw_columns(ctx, demo_state.presets, {
            selected_ids = demo_state.selected_presets,
            search_text = demo_state.search_text,
            use_dot_style = true,
            bg_color = hexrgb("#252530"),
            dot_size = 7,
            dot_spacing = 7,
            rounding = 5,
            padding_h = 12,
            column_width = 180,
            column_spacing = 16,
            item_spacing = 3,
          })
        else
          clicked_preset = ChipList.draw(ctx, demo_state.presets, {
            max_width = w - padding_h * 2,
            selected_ids = demo_state.selected_presets,
            search_text = demo_state.search_text,
            use_dot_style = true,
            bg_color = hexrgb("#252530"),
            dot_size = 7,
            dot_spacing = 7,
            rounding = 5,
            padding_h = 12,
            chip_spacing = 3,
            line_spacing = 3,
            justified = true,
            max_stretch_ratio = 1.4,
          })
        end
        
        if clicked_preset then
          demo_state.selected_presets = {}
          demo_state.selected_presets[clicked_preset] = true
          window.overlay:pop('preset-browser')
        end
      end, { 
        title = "Preset Browser", 
        width = 0.65, 
        height = 0.75,
        config = custom_config
      })
    end
  })
end

local function draw_mock_content(ctx)
  ImGui.Text(ctx, "Chip List + Modal Overlay Demo (with Justified Layout)")
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 10)
  
  ImGui.Text(ctx, "Click buttons to open modals with justified chip lists:")
  ImGui.Dummy(ctx, 0, 12)
  
  if ImGui.Button(ctx, "Tag Selector (Justified Wrap)", 250, 40) then
    demo_state.search_text = ""
    create_tag_selector_modal(_G.demo_window)
  end
  
  ImGui.SameLine(ctx)
  ImGui.Dummy(ctx, 12, 0)
  ImGui.SameLine(ctx)
  
  if ImGui.Button(ctx, "Preset Browser (with Layout Modes)", 250, 40) then
    demo_state.search_text = ""
    create_preset_browser_modal(_G.demo_window)
  end
  
  ImGui.Dummy(ctx, 0, 20)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 12)
  
  ImGui.Text(ctx, "Selected Tags:")
  ImGui.Dummy(ctx, 0, 8)
  
  local selected_tag_items = {}
  for _, tag in ipairs(demo_state.tags) do
    if demo_state.selected_tags[tag.id] then
      table.insert(selected_tag_items, tag)
    end
  end
  
  if #selected_tag_items > 0 then
    local clicked_tag = ChipList.draw(ctx, selected_tag_items, {
      chip_spacing = 8,
      line_spacing = 8,
      justified = true,
      max_stretch_ratio = 1.25,
    })
    
    if clicked_tag then
      demo_state.selected_tags[clicked_tag] = false
    end
  else
    ImGui.TextDisabled(ctx, "  No tags selected")
  end
  
  ImGui.Dummy(ctx, 0, 20)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 12)
  
  ImGui.Text(ctx, "Available Tags (inline justified example):")
  ImGui.Dummy(ctx, 0, 8)
  
  local inline_clicked = ChipList.draw(ctx, demo_state.tags, {
    chip_spacing = 8,
    line_spacing = 8,
    selected_ids = demo_state.selected_tags,
    justified = true,
    max_stretch_ratio = 1.3,
  })
  
  if inline_clicked then
    demo_state.selected_tags[inline_clicked] = not demo_state.selected_tags[inline_clicked]
  end
  
  ImGui.Dummy(ctx, 0, 20)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 12)
  
  ImGui.Text(ctx, "Selected Preset:")
  ImGui.Dummy(ctx, 0, 8)
  
  local selected_preset = nil
  for _, preset in ipairs(demo_state.presets) do
    if demo_state.selected_presets[preset.id] then
      selected_preset = preset
      break
    end
  end
  
  if selected_preset then
    local clicked = ChipList.draw_grid(ctx, {selected_preset}, {
      cols = 1,
      gap = 8,
      use_dot_style = true,
      bg_color = hexrgb("#252530"),
      selected_ids = demo_state.selected_presets,
      dot_size = 7,
    })
    
    if clicked then
      demo_state.selected_presets[clicked] = false
    end
  else
    ImGui.TextDisabled(ctx, "  No preset selected")
  end
  
  ImGui.Dummy(ctx, 0, 12)
  ImGui.TextDisabled(ctx, "Tip: Chips expand to fill full row width proportionally")
  ImGui.Dummy(ctx, 0, 8)
  ImGui.TextDisabled(ctx, "Note: Use Preset Browser to switch between layout modes")
  
  ImGui.Dummy(ctx, 0, 16)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)
  ImGui.TextWrapped(ctx, "Config: max_stretch_ratio controls expansion limit (1.3 = max 30% wider)")
end

local function main()
  Shell.run({
    title = "Chip List + Modal Demo (Layout Modes)",
    style = style_ok and Style or nil,
    initial_pos = { x = 140, y = 140 },
    initial_size = { w = 900, h = 800 },
    min_size = { w = 700, h = 600 },
    
    draw = function(ctx, state)
      _G.demo_window = state.window
      draw_mock_content(ctx)
    end,
  })
end

main()