local M = {}

---@class Riches.SystemMessageOptions
---@field text string
---@field cached? boolean

---@class Riches.SystemMessage
---@field type string
---@field text string
---@field cache_control? { type: string }

---@class Riches.UserMessageOptions
---@field text string
---@field cached? boolean

---@class Riches.UserMessage
---@field content { type: string, text: string }[]
---@field cache_control? { type: string }

--- Create a system message
---@param opts Riches.SystemMessageOptions
---@return Riches.SystemMessage
M.system_message = function(opts)
  local text = opts.text
  local cached = opts.cached

  local message = {
    type = "text",
    text = text,
  }

  if cached then
    message.cache_control = { type = "ephemeral" }
  end

  return message
end

--- Create a user message
---@param opts Riches.UserMessageOptions
---@return Riches.UserMessage
M.user_message = function(opts)
  local text = opts.text
  local cached = opts.cached

  local message = {
    role = "user",
    content = {
      {
        type = "text",
        text = text,
      },
    },
  }

  if cached then
    message.content[1].cache_control = { type = "ephemeral" }
  end

  return message
end

return M
