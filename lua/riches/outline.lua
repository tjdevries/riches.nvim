--
-- local parser = assert(vim.treesitter.get_parser(buf), "Must have a parser")
--

-- local query_text = [[
-- ((call
--    target: (identifier) @name
--    (arguments) @args
--    (do_block))
--  (#eq? @name "def"))
-- ]]

-- local query = vim.treesitter.query.parse("elixir", query_text)
-- print(query)

-- local root = assert(parser:parse()[1]:root(), "Must have a root")
-- for _, match, metadata in query:iter_matches(root, buf, 0, -1) do
--   for id, nodes in pairs(match) do
--     local name = query.captures[id]
--     if name == "args" then
--       local node = nodes[1]
--       print(vim.treesitter.get_node_text(node, buf))
--     end
--   end
-- end

local M = {}

--- This is from LUA LSP
---@param ctx riches.FileContext
---@param lines string[]
---@return string[]
M.treesitter = function(ctx, lines)
  -- This code is inspired from https://github.com/stevearc/aerial.nvim/tree/master
  local get_node_text = vim.treesitter.get_node_text

  local extensions = require "aerial.backends.treesitter.extensions"
  local helpers = require "aerial.backends.treesitter.helpers"
  local config = require "aerial.config"

  -- local include_kind = config.get_filter_kind_map(bufnr)

  local items = {}

  local content = table.concat(lines, "\n")
  local parser = vim.treesitter.get_string_parser(content, ctx.lang)
  if not parser then
    return lines
  end

  local lang = parser:lang()
  local syntax_tree = parser:parse()[1]
  local query = helpers.get_query(lang)
  if not query or not syntax_tree then
    return lines
  end

  -- This will track a loose hierarchy of recent node+items.
  -- It is used to determine node parents for the tree structure.
  local stack = {}
  local ext = extensions[lang]
  for _, matches, metadata in query:iter_matches(syntax_tree:root(), content, nil, nil, { all = false }) do
    ---@note mimic nvim-treesitter's query.iter_group_results return values:
    --       {
    --         kind = "Method",
    --         name = {
    --           metadata = {
    --             range = { 2, 11, 2, 20 }
    --           },
    --           node = <userdata 1>
    --         },
    --         type = {
    --           node = <userdata 2>
    --         }
    --       }
    --- Matches can overlap. The last match wins.
    local match = vim.tbl_extend("force", {}, metadata)
    for id, node in pairs(matches) do
      -- iter_group_results prefers `#set!` metadata, keeping the behaviour
      match = vim.tbl_extend("keep", match, {
        [query.captures[id]] = {
          metadata = metadata[id],
          node = node,
        },
      })
    end

    local name_match = match.name or {}
    local selection_match = match.selection or {}
    local symbol_node = (match.symbol or match.type or {}).node
    -- The location capture groups are optional. We default to the
    -- location of the @symbol capture
    local start_node = (match.start or {}).node or symbol_node
    local end_node = (match["end"] or {}).node or start_node
    local parent_item, parent_node, level = ext.get_parent(stack, match, symbol_node)
    -- Sometimes our queries will match the same node twice.
    -- Detect that (symbol_node == parent_node), and skip dupes.
    if not symbol_node or symbol_node == parent_node then
      goto continue
    end
    local kind = match.kind
    if not kind then
      vim.api.nvim_err_writeln(string.format("Missing 'kind' metadata in query file for language %s", lang))
      break
    elseif not vim.lsp.protocol.SymbolKind[kind] then
      vim.api.nvim_err_writeln(string.format("Invalid 'kind' metadata '%s' in query file for language %s", kind, lang))
      break
    end
    local range = helpers.range_from_nodes(start_node, end_node)
    local selection_range
    if selection_match.node then
      selection_range = helpers.range_from_nodes(selection_match.node, selection_match.node)
    end
    local name
    if name_match.node then
      name = get_node_text(name_match.node, content, name_match) or "<parse error>"
      if not selection_range then
        selection_range = helpers.range_from_nodes(name_match.node, name_match.node)
      end
    else
      name = "<Anonymous>"
    end
    local scope
    if match.scope and match.scope.node then -- we've got a node capture on our hands
      scope = get_node_text(match.scope.node, content, match.scope)
    else
      scope = match.scope
    end
    ---@type aerial.Symbol
    local item = {
      kind = kind,
      name = name,
      level = level,
      lnum = range.lnum,
      end_lnum = range.end_lnum,
      col = range.col,
      end_col = range.end_col,
      parent = parent_item,
      selection_range = selection_range,
      scope = scope,
    }

    if item.parent then
      if not item.parent.children then
        item.parent.children = {}
      end
      table.insert(item.parent.children, item)
    else
      table.insert(items, item)
    end
    table.insert(stack, { node = symbol_node, item = item })

    ::continue::
  end
  ext.postprocess_symbols(content, items)

  local transformed = {}
  local handled = {}

  local handle_item

  --- Handle an item
  ---@param item aerial.Symbol
  handle_item = function(item)
    if handled[item] then
      return
    end

    table.insert(transformed, lines[item.lnum])
    if item.end_lnum - item.lnum > 1 then
      table.insert(transformed, "# ...")
    end

    for _, child in ipairs(item.children or {}) do
      handle_item(child)
    end

    if item.end_lnum ~= item.lnum then
      table.insert(transformed, lines[item.end_lnum])
    end

    handled[item] = true
  end

  for _, item in ipairs(items) do
    handle_item(item)
  end

  return transformed
end

return M
