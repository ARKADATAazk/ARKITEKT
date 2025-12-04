-- @noindex
-- arkitekt/gui/widgets/tree/init.lua
-- Tree widget: Ark.Tree(ctx, opts) for single-column tree
-- Also exports Ark.Tree.TreeTable(ctx, opts) for multi-column

local Tree = require('arkitekt.gui.widgets.tree.tree')
local TreeTable = require('arkitekt.gui.widgets.tree.tree_table')

-- ============================================================================
-- MODULE EXPORTS
-- ============================================================================

--- Single-column tree widget (main export)
--- Usage: Ark.Tree(ctx, { id = 'folders', nodes = data })
--- @param ctx userdata ImGui context
--- @param opts table Options { id, nodes, on_select, ... }
--- @return table Result object
local M = setmetatable({
  -- Tree methods
  Draw = Tree.Draw,
  expand_to_node = Tree.expand_to_node,
  select_node = Tree.select_node,
  clear_selection = Tree.clear_selection,
  get_selected = Tree.get_selected,
  expand_all = Tree.expand_all,
  collapse_all = Tree.collapse_all,
  start_rename = Tree.start_rename,

  -- TreeTable as sub-export: Ark.Tree.TreeTable(ctx, opts)
  TreeTable = setmetatable({
    Draw = TreeTable.Draw,
    expand_to_node = TreeTable.expand_to_node,
    select_node = TreeTable.select_node,
    clear_selection = TreeTable.clear_selection,
    get_selected = TreeTable.get_selected,
    expand_all = TreeTable.expand_all,
    collapse_all = TreeTable.collapse_all,
    start_rename = TreeTable.start_rename,
  }, {
    __call = function(_, ctx, opts)
      return TreeTable.Draw(ctx, opts)
    end
  }),

  -- Core modules for advanced usage
  Config = require('arkitekt.gui.widgets.tree.config'),
  State = require('arkitekt.gui.widgets.tree.core.state'),
}, {
  __call = function(_, ctx, opts)
    return Tree.Draw(ctx, opts)
  end
})

return M
