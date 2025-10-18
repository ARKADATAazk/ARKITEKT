local State = {}

local DEFAULT_STATE = {
    playlists = {
        active_id = nil,
        items = {},
        sequence_cache = nil,
    },
    playback = {
        is_playing = false,
        loop = false,
        cursor_pos = 0,
    },
    regions = {
        by_id = {},
    },
    ui = {
        selection = {},
        panel_state = {},
    },
}

local DOMAIN_KEYS = {
    playlists = {
        active_id = true,
        items = true,
        sequence_cache = true,
    },
    playback = {
        is_playing = true,
        loop = true,
        cursor_pos = true,
    },
    regions = {
        by_id = true,
    },
    ui = {
        selection = true,
        panel_state = true,
    },
}

local instances = {}

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

local function normalize_key_path(key_path)
    local normalized = {}

    if type(key_path) == "string" then
        for segment in string.gmatch(key_path, "[^%.]+") do
            normalized[#normalized + 1] = segment
        end
    elseif type(key_path) == "table" then
        for i = 1, #key_path do
            normalized[i] = key_path[i]
        end
    else
        error("keyPath must be a string or table")
    end

    if #normalized == 0 then
        error("keyPath cannot be empty")
    end

    return normalized
end

local function path_to_string(path, upto)
    local limit = upto or #path
    local parts = {}
    for i = 1, limit do
        parts[i] = tostring(path[i])
    end
    return table.concat(parts, ".")
end

local Instance = {}
Instance.__index = Instance

local function create_instance(project_id)
    local instance = {
        _project_id = project_id,
        _state = deep_copy(DEFAULT_STATE),
        _listeners = {},
        _listener_registry = {},
        _next_listener_id = 1,
        _tx_active = false,
        _pending_domains = nil,
    }

    return setmetatable(instance, Instance)
end

local function validate_domain(path)
    local domain = path[1]
    local schema = DOMAIN_KEYS[domain]

    if not schema then
        error(string.format("Unknown domain '%s'", tostring(domain)))
    end

    if path[2] ~= nil then
        local key = path[2]
        if not schema[key] then
            error(string.format("Unknown key '%s' for domain '%s'", tostring(key), domain))
        end
    end

    return domain, schema
end

function Instance:_mark_domain_changed(domain)
    if self._tx_active then
        self._pending_domains[domain] = true
        return
    end

    self:emit(domain .. ".changed", deep_copy(self._state[domain]))
end

function Instance:get(key_path)
    local path = normalize_key_path(key_path)
    local domain = validate_domain(path)
    local value = self._state

    for i = 1, #path do
        local key = path[i]
        value = value[key]
        if value == nil then
            break
        end
    end

    return deep_copy(value)
end

local function assign_domain(instance, domain, schema, value)
    if type(value) ~= "table" then
        error(string.format("Value for domain '%s' must be a table", domain))
    end

    for key in pairs(value) do
        if not schema[key] then
            error(string.format("Unknown key '%s' for domain '%s'", tostring(key), domain))
        end
    end

    local result = {}
    for key in pairs(schema) do
        if value[key] ~= nil then
            result[key] = deep_copy(value[key])
        else
            result[key] = deep_copy(DEFAULT_STATE[domain][key])
        end
    end

    instance._state[domain] = result
end

local function assign_path(instance, path, value)
    local target = instance._state
    for i = 1, #path - 1 do
        local segment = path[i]
        local next_value = target[segment]

        if i < #path - 1 then
            if next_value == nil then
                next_value = {}
                target[segment] = next_value
            elseif type(next_value) ~= "table" then
                error(string.format("Cannot set nested key for non-table segment '%s'", path_to_string(path, i)))
            end
            target = next_value
        else
            if next_value == nil then
                next_value = {}
                target[segment] = next_value
            elseif type(next_value) ~= "table" then
                error(string.format("Cannot set child value for non-table segment '%s'", path_to_string(path, i)))
            end
            target = next_value
        end
    end
    target[path[#path]] = deep_copy(value)
end

function Instance:set(key_path, value)
    local path = normalize_key_path(key_path)
    local domain, schema = validate_domain(path)

    if #path == 1 then
        assign_domain(self, domain, schema, value)
    else
        assign_path(self, path, value)
    end

    self:_mark_domain_changed(domain)
end

function Instance:tx(fn)
    if type(fn) ~= "function" then
        error("Transaction callback must be a function")
    end

    if self._tx_active then
        error("A transaction is already in progress")
    end

    self._tx_active = true
    self._pending_domains = {}

    local ok, result_or_err = pcall(fn, self)

    self._tx_active = false
    local pending = self._pending_domains
    self._pending_domains = nil

    if not ok then
        error(result_or_err)
    end

    for domain in pairs(pending) do
        self:emit(domain .. ".changed", deep_copy(self._state[domain]))
    end

    return result_or_err
end

function Instance:on(event, handler)
    if type(event) ~= "string" then
        error("Event name must be a string")
    end

    if type(handler) ~= "function" then
        error("Event handler must be a function")
    end

    local id = self._next_listener_id
    self._next_listener_id = id + 1

    if not self._listeners[event] then
        self._listeners[event] = {}
    end

    self._listeners[event][id] = handler
    self._listener_registry[id] = event

    return id
end

function Instance:off(id)
    local event = self._listener_registry[id]
    if not event then
        return
    end

    self._listener_registry[id] = nil

    local listeners = self._listeners[event]
    if listeners then
        listeners[id] = nil
        if next(listeners) == nil then
            self._listeners[event] = nil
        end
    end
end

function Instance:emit(event, payload)
    local listeners = self._listeners[event]
    if not listeners then
        return
    end

    -- Iterate over a snapshot to prevent modifications during emit
    local snapshot = {}
    for id, handler in pairs(listeners) do
        snapshot[#snapshot + 1] = handler
    end

    for i = 1, #snapshot do
        snapshot[i](payload)
    end
end

function State.for_project(project_id)
    local id = project_id or 0
    if instances[id] == nil then
        instances[id] = create_instance(id)
    end
    return instances[id]
end

return State
