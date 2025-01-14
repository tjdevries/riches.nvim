local M = {}

local codeblock_query = vim.treesitter.query.parse(
  "markdown",
  [[ (fenced_code_block
       (info_string (language) @language)
       (code_fence_content) @code) @block ]]
)

local transform_filename = function(line)
  local filename = vim.split(vim.trim(string.sub(line, 6)), " ")[1]
  local date = os.date "%Y%m%d%H%M%S"
  return (filename:gsub("%[timestamp%]", date):gsub("TIMESTAMP", date))
end

--- Get the filename from a response
---@param lines string[]
---@param row integer
---@return string?
local get_filename = function(lines, row)
  while row > 0 do
    local line = lines[row]

    if vim.startswith(line, "FILE:") then
      return transform_filename(line)
    end

    row = row - 1
  end

  return nil
end

M.parse = function(lines)
  local content = table.concat(lines, "\n")

  local parser = vim.treesitter.get_string_parser(content, "markdown")
  local tree = parser:parse()[1]
  local root = tree:root()

  local result = {}
  for _, match in codeblock_query:iter_matches(root, content, 0, -1) do
    -- local language = match[1][1]
    local code = match[2][1]
    local block = match[3][1]

    local start_row, _, _, _ = block:range()
    local file = get_filename(lines, start_row)

    table.insert(result, {
      code = vim.treesitter.get_node_text(code, content),
      file = file,
    })
  end

  return result
end

return M
