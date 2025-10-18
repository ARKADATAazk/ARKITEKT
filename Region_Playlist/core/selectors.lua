local selectors = {}

function selectors.active_playlist_id(state)
    if type(state) ~= "table" then
        return nil
    end

    local playlists = state.playlists
    if type(playlists) ~= "table" then
        return nil
    end

    return playlists.active_id
end

function selectors.active_items(state)
    if type(state) ~= "table" then
        return nil
    end

    local playlists = state.playlists
    if type(playlists) ~= "table" then
        return nil
    end

    local active_id = playlists.active_id
    if not active_id then
        return nil
    end

    local items = playlists.items
    if type(items) ~= "table" then
        return nil
    end

    return items[active_id]
end

return selectors
