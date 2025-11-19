-- @noindex
-- Debug logging utility for ItemPicker
local M = {}

local log_file_path = reaper.GetResourcePath() .. "/itempicker_debug.log"

function M.clear()
    local file = io.open(log_file_path, "w")
    if file then
        file:close()
    end
end

function M.log(category, message)
    local file = io.open(log_file_path, "a")
    if file then
        local timestamp = os.date("%H:%M:%S")
        file:write(string.format("[%s] [%s] %s\n", timestamp, category, tostring(message)))
        file:close()
    end
end

function M.log_checkbox(id, clicked, is_checked, total_width)
    M.log("CHECKBOX", string.format("id=%s, clicked=%s, is_checked=%s, width=%s",
        id, tostring(clicked), tostring(is_checked), tostring(total_width)))
end

function M.log_drag_start(item)
    M.log("DRAG", string.format("Drag started: item=%s", tostring(item)))
end

function M.log_drag_end()
    M.log("DRAG", "Drag ended")
end

function M.log_mouse_wheel(delta, context)
    M.log("SCROLL", string.format("Mouse wheel: delta=%s, context=%s", tostring(delta), context))
end

function M.log_tile_click(tile_index, item)
    M.log("TILE", string.format("Tile clicked: index=%s, item=%s", tostring(tile_index), tostring(item)))
end

return M
