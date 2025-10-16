-- ReaImGui Black Click-Through Window
-- Draws a black window that ignores all inputs
-- Compatible with ReaImGui 0.10.0

local r = reaper
package.path = r.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/?.lua'
local ImGui = require('imgui')('0.10')

local ctx = ImGui.CreateContext('Black Click-Through Window')

function loop()
    ImGui.PushStyleColor(ctx, ImGui.Col_WindowBg, 0x000000FF)
    
    ImGui.SetNextWindowPos(ctx, 100, 100, ImGui.Cond_FirstUseEver)
    ImGui.SetNextWindowSize(ctx, 400, 300, ImGui.Cond_FirstUseEver)
    
    local window_flags = ImGui.WindowFlags_NoTitleBar |
                         ImGui.WindowFlags_NoResize |
                         ImGui.WindowFlags_NoMove |
                         ImGui.WindowFlags_NoScrollbar |
                         ImGui.WindowFlags_NoScrollWithMouse |
                         ImGui.WindowFlags_NoCollapse |
                         ImGui.WindowFlags_NoNav |
                         ImGui.WindowFlags_NoInputs
    
    local visible, open = ImGui.Begin(ctx, 'Black Window', true, window_flags)
    
    if visible then
        ImGui.End(ctx)
    end
    
    ImGui.PopStyleColor(ctx)
    
    if open then
        r.defer(loop)
    end
end

r.defer(loop)