local M = {}

function M.Pickle(t)
  return M.PickleTable:clone():pickle_(t)
end

M.PickleTable = {
  clone = function(t)
    local nt = {}
    for i, v in pairs(t) do nt[i] = v end
    return nt
  end
}

function M.PickleTable:pickle_(root)
  if type(root) ~= "table" then
    error("can only pickle tables, not " .. type(root) .. "s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #self._refToTable > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s .. "{\n"
    for i, v in pairs(t) do
      s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s .. "},\n"
  end

  return string.format("{%s}", s)
end

function M.PickleTable:value_(v)
  local vtype = type(v)
  if vtype == "string" then
    return string.format("%q", v)
  elseif vtype == "number" then
    return v
  elseif vtype == "boolean" then
    return tostring(v)
  elseif vtype == "table" then
    return "{" .. self:ref_(v) .. "}"
  else
  end
end

function M.PickleTable:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #self._refToTable
    self._tableToRef[t] = ref
  end
  return ref
end

function M.Unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a " .. type(s) .. ", only strings")
  end
  local gentables = load("return " .. s)
  local tables = gentables()

  for tnum = 1, #tables do
    local t = tables[tnum]
    local tcopy = {}
    for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end

return M