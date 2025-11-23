-- @noindex
-- arkitekt/defs/reaper_commands.lua
-- REAPER action command IDs

local M = {}

-- ============================================================================
-- ITEM COMMANDS
-- ============================================================================
M.ITEM = {
    REMOVE = 40289,             -- Item: Remove items/tracks/envelope points/markers/regions/... (Time selection)
    SPLIT = 40012,              -- Item: Split items at edit cursor
    COPY = 40698,               -- Edit: Copy items
    PASTE = 40058,              -- Item: Paste items/tracks
    SELECT_ALL = 40182,         -- Item: Select all items
    UNSELECT_ALL = 40289,       -- Item: Unselect all items
}

-- ============================================================================
-- TRACK COMMANDS
-- ============================================================================
M.TRACK = {
    SELECT_ALL = 40296,         -- Track: Select all tracks
    UNSELECT_ALL = 40297,       -- Track: Unselect all tracks
    COPY = 40210,               -- Track: Copy tracks
    PASTE = 40058,              -- Track: Paste tracks/items
    INSERT = 40001,             -- Track: Insert new track
    DELETE = 40005,             -- Track: Remove tracks
}

-- ============================================================================
-- TRANSPORT COMMANDS
-- ============================================================================
M.TRANSPORT = {
    PLAY = 1007,                -- Transport: Play
    STOP = 1016,                -- Transport: Stop
    PAUSE = 1008,               -- Transport: Pause
    RECORD = 1013,              -- Transport: Record
    REWIND = 40042,             -- Transport: Go to start of project
    GOTO_END = 40043,           -- Transport: Go to end of project
}

-- ============================================================================
-- PROJECT COMMANDS
-- ============================================================================
M.PROJECT = {
    NEW = 40023,                -- File: New project
    NEW_TAB = 41929,            -- File: New project tab (ignore default template)
    SAVE = 40026,               -- File: Save project
    SAVE_AS = 40022,            -- File: Save project as
    OPEN = 40025,               -- File: Open project
}

-- ============================================================================
-- EDIT COMMANDS
-- ============================================================================
M.EDIT = {
    UNDO = 40029,               -- Edit: Undo
    REDO = 40030,               -- Edit: Redo
    COPY = 40057,               -- Edit: Copy
    PASTE = 40058,              -- Edit: Paste
    CUT = 40059,                -- Edit: Cut
    DELETE = 40697,             -- Edit: Remove content
}

-- ============================================================================
-- VIEW COMMANDS
-- ============================================================================
M.VIEW = {
    SMOOTH_SCROLL_TOGGLE = 41817,   -- View: Toggle smooth seeking
    TOGGLE_MIXER = 40078,           -- View: Toggle mixer visible
    ZOOM_FIT = 40295,               -- View: Zoom to selected items
}

-- ============================================================================
-- MIXER COMMANDS
-- ============================================================================
M.MIXER = {
    TOGGLE_MASTER = 41588,      -- View: Toggle hide master track in mixer
    TOGGLE_FOLDER_PARENT = 40864,   -- View: Toggle folder parent indicator in mixer
}

-- ============================================================================
-- MARKER/REGION COMMANDS
-- ============================================================================
M.MARKER = {
    INSERT_MARKER = 40157,      -- Markers: Insert marker at current position
    INSERT_REGION = 40174,      -- Markers: Insert region from time selection
    REMOVE_ALL_MARKERS = 40182, -- Markers: Remove all markers
    REMOVE_ALL_REGIONS = 40615, -- Markers: Remove all regions
}

-- ============================================================================
-- ACTIONS (by ID from various scripts)
-- ============================================================================
M.ACTION = {
    APPLY_TRACK_COLOR = 41337,  -- Track: Apply track color to track items
}

return M
