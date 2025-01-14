vim.filetype.add {
  extension = {
    ex = "elixir",
  },
}

local default_system = "You are a professional software developer who has experience in writing lots of great software."

local riches = require "riches"

local prompt_buf = vim.api.nvim_create_buf(false, true)
vim.bo[prompt_buf].filetype = "markdown"

local result_buf = vim.api.nvim_create_buf(false, true)
vim.bo[result_buf].filetype = "markdown"

local focus = function()
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local win = vim.api.nvim_tabpage_get_win(tab)
    if vim.api.nvim_win_get_buf(win) == prompt_buf or vim.api.nvim_win_get_buf(win) == result_buf then
      vim.api.nvim_set_current_tabpage(tab)
      return
    end
  end

  vim.cmd.tabnew()
  vim.cmd [[0tabmove]]
  vim.cmd.mode()

  local result_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(result_win, result_buf)
  vim.wo[result_win].winbar = "[riches] Result"

  local prompt_win = vim.api.nvim_open_win(prompt_buf, true, {
    split = "below",
    height = 10,
  })
  vim.wo[prompt_win].winbar = "[riches] Prompt"
end

--- Get the filename from a response
---@param contents string[]
---@return string?
local get_filename = function(contents)
  for _, line in ipairs(contents) do
    line = vim.trim(line)

    if vim.startswith(line, "FILE:") then
      return vim.trim(string.sub(line, 6))
    end
  end

  return nil
end

vim.api.nvim_create_user_command("RichesTest", function()
  local rules = riches.find_local_rules_file()
  local result = riches.eval_rules(rules)

  focus()

  local win = vim.api.nvim_get_current_win()
  local keymaps = {
    ["<space>aa"] = function()
      local contents = vim.api.nvim_buf_get_lines(result_buf, 0, -1, false)
      local parsed = require("riches.parse_markdown").parse(contents)

      vim.cmd.tabnew()
      for idx, block in ipairs(parsed) do
        if idx == 1 then
          vim.cmd.edit(block.file)
        else
          vim.cmd.split(block.file)
        end

        if #vim.api.nvim_buf_get_lines(0, 0, -1, false) <= 1 then
          vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(block.code, "\n"))
        end
      end
    end,

    ["<CR>"] = function()
      local message = string.format(
        "%s\n%s",
        table.concat(result, "\n"),
        table.concat(vim.api.nvim_buf_get_lines(prompt_buf, 0, -1, false), "\n")
      )

      riches.send_to_llm {
        system = rules.system or default_system,
        message = message,
        stream = function(_, data)
          data = vim.trim(data)
          if not vim.startswith(data, "data:") then
            return
          end

          local ok, decoded = pcall(vim.json.decode, vim.trim(data:sub(6)))
          if not ok then
            return
          end

          if decoded.type ~= "content_block_delta" then
            return
          end

          vim.api.nvim_buf_set_text(result_buf, -1, -1, -1, -1, vim.split(decoded.delta.text, "\n"))
          pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(result_buf), 0 })
        end,
        callback = function(data)
          print("done", data)
        end,
      }
    end,
  }

  for key, mapping in pairs(keymaps) do
    vim.keymap.set("n", key, mapping, { buffer = prompt_buf })
  end

  -- local win = vim.api.nvim_open_win(buf, true, {
  --   relative = "editor",
  --   row = 1,
  --   col = 1,
  --   width = vim.o.columns - 10,
  --   height = vim.o.lines - 10,
  --   style = "minimal",
  --   border = "single",
  -- })

  -- vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, vim.split(message, "\n"))
end, {})

vim.api.nvim_create_user_command("RichesGenerate", function()
  local rules = riches.find_local_rules_file()
  local result = riches.eval_rules(rules)

  local task = vim.fn.input "Task: "

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()

  local popup_buf = vim.api.nvim_create_buf(false, true)
  local popup_win = vim.api.nvim_open_win(popup_buf, true, {
    relative = "editor",
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = 1,
    col = 1,
    style = "minimal",
    border = "single",
  })

  local system = string.format(
    [[
%s

You will return a response that starts with
<GENERATED_CODE>

and ends with
</GENERATED_CODE>

You can list any steps you needed to think through to get to this response before you send the <GENERATED_CODE> tag,
but you should not include any code that is not related to the task at hand.

I will insert the <GENERATED_CODE> into the buffer to solve the problem.
]],
    rules.system or default_system
  )

  local message = string.format("%s\n%s", table.concat(result, "\n"), task)

  riches.send_to_llm {
    stop_sequences = { "</GENERATED_CODE>" },
    system = system,
    message = message,
    stream = function(_, data)
      data = vim.trim(data)
      if not vim.startswith(data, "data:") then
        return
      end

      local ok, decoded = pcall(vim.json.decode, vim.trim(data:sub(6)))
      if not ok then
        return
      end

      if decoded.type ~= "content_block_delta" then
        return
      end

      vim.api.nvim_buf_set_text(popup_buf, -1, -1, -1, -1, vim.split(decoded.delta.text, "\n"))
      pcall(vim.api.nvim_win_set_cursor, popup_win, { vim.api.nvim_buf_line_count(result_buf), 0 })
    end,
    callback = function(_) end,
  }
end, {})
