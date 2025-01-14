package.loaded["riches.prompt"] = nil

local curl = require "plenary.curl"

local dotenv = require "custom.dotenv"
local parsed = dotenv.parse "/home/tjdevries/plugins/riches.nvim/.env"
local api_key = parsed.ANTHROPIC_TOKEN or os.getenv "ANTHROPIC_TOKEN"

local prompt_lib = require "riches.prompt"

RICHES_TMP_FILE = RICHES_TMP_FILE or vim.fn.tempname()

---@class riches.FileContext
---@field path string
---@field lang string

local M = {}

local open_floating_window = function()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "riches"
  vim.api.nvim_buf_set_name(bufnr, "riches")

  vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = 1,
    col = 1,
    width = vim.o.columns - 10,
    height = vim.o.lines - 10,
    style = "minimal",
    border = "single",
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    callback = function()
      pcall(vim.api.nvim_win_close, 0, true)
    end,
  })
end

M.find_local_rules_file = function()
  local rules_file = vim.fs.find(".riches.lua", { upward = true })
  if rules_file[1] then
    -- local contents = vim.secure.read(rules_file[1])
    local contents = table.concat(vim.fn.readfile(rules_file[1]), "\n")
    if contents then
      return loadstring(contents)()
    end
  else
    return {}
  end
end

M.eval_rules = function(rules)
  local context = {}

  local include_patterns = rules.include or {}
  for _, rule in ipairs(include_patterns) do
    local transforms = rule.transforms or {}

    for _, glob in ipairs(rule) do
      for _, file in ipairs(vim.fn.glob(glob, true, true)) do
        local ctx = {
          file = file,
          lang = vim.filetype.match { filename = file },
        }

        local contents = vim.fn.readfile(file)
        for _, transform in ipairs(transforms) do
          contents = transform(ctx, contents)
        end

        if contents then
          table.insert(
            context,
            string.format("File: %s\n```%s\n%s\n```\n", file, ctx.lang, table.concat(contents, "\n"))
          )
        end
      end
    end
  end

  return context
end

M.query = function(opts)
  local rules = M.find_local_rules_file()
  local context = M.eval_rules(rules)

  return context
end

M.send_to_llm = function(opts)
  local json_body = vim.json.encode {
    model = "claude-3-5-sonnet-20241022",
    stream = not not opts.stream,
    max_tokens = 4096,
    temperature = 0.1,
    system = {
      prompt_lib.system_message {
        text = opts.system,
      },
    },
    messages = {
      prompt_lib.user_message {
        text = opts.message,
      },
    },
    stop_sequences = opts.stop_sequences,
  }

  vim.fn.writefile(vim.split(json_body, "\n"), RICHES_TMP_FILE)

  pcall(curl.post, {
    timeout = 1000 * 60,
    url = "https://api.anthropic.com/v1/messages",
    headers = {
      ["x-api-key"] = api_key,
      ["content-type"] = "application/json",
      ["anthropic-version"] = "2023-06-01",
      -- ["anthropic-beta"] = "prompt-caching-2024-07-31",
    },
    raw = { "--no-buffer" },
    body = RICHES_TMP_FILE,
    stream = opts.stream and vim.schedule_wrap(opts.stream),
    callback = vim.schedule_wrap(opts.callback),
  })
end

return M
