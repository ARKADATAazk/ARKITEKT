local Persistence = {}

local function deep_copy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deep_copy(v)
    end
    return copy
end

local function normalize_loaded_data(raw)
    local normalized = {
        playlists = {},
        active_id = nil,
    }

    if type(raw) == "table" then
        if type(raw.playlists) == "table" then
            normalized.playlists = deep_copy(raw.playlists)
        end

        if raw.active_id ~= nil then
            normalized.active_id = raw.active_id
        end
    end

    return normalized
end

local function extract_persistable(data)
    local sanitized = {
        playlists = {},
        active_id = nil,
    }

    if type(data) ~= "table" then
        return sanitized
    end

    if type(data.playlists) == "table" then
        sanitized.playlists = deep_copy(data.playlists)
    end

    if data.active_id ~= nil then
        sanitized.active_id = data.active_id
    end

    return sanitized
end

function Persistence.load(project_id)
    -- TODO: integrate with actual persistence backend for project-specific storage.
    local raw = nil
    return normalize_loaded_data(raw)
end

function Persistence.save(project_id, data)
    local _ = extract_persistable(data)
    -- TODO: persist payload for the given project identifier.
    return false
end

return Persistence
