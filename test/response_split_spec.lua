local eq = assert.are.same

local simple_elixir = [[
FILE: priv/repo/migrations/add_superuser_to_users.ex
```elixir
defmodule FamBook.Repo.Migrations.AddSuperuserToUsers do
end
```
]]

local multi_elixir = [[
FILE: lib/fambook/accounts/user.ex (add to schema)
```elixir
content
```

FILE: lib/fambook/accounts/user.ex (add to registration_changeset function)
```elixir
content
```
]]

describe("ResponseSplit", function()
  it("should split a single markdown block", function()
    local lines = vim.split(simple_elixir, "\n")
    local parsed = require("riches.parse_markdown").parse(lines)
    eq({
      {
        file = "priv/repo/migrations/add_superuser_to_users.ex",
        code = "defmodule FamBook.Repo.Migrations.AddSuperuserToUsers do\nend\n",
      },
    }, parsed)
  end)

  it("should split multiple markdown block", function()
    local lines = vim.split(multi_elixir, "\n")
    local parsed = require("riches.parse_markdown").parse(lines)
    eq({
      {
        file = "lib/fambook/accounts/user.ex",
        code = "content\n",
      },
      {
        file = "lib/fambook/accounts/user.ex",
        code = "content\n",
      },
    }, parsed)
  end)
end)
