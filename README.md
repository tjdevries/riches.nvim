# riches.nvim

We got ourselves a RAGs to riches kind of scenario here. Gather and manage context for your neovim session, and then send it to some LLM - i don't care who.

We gotta make ourselves rich shipping so fast.

## Installation

You should just know by now.

## Usage

who knows.

## Thoughts

Two-phase LLM shenanigans.

1. do what we're doing so far
2. LLM responds with file paths that are relevant.
3. read those files, send as new message
4. ask for a diff to update the files

## Example Usage

```lua
-- TODO: Caching (some files should be cached maybe?)

return {
	system = [[
You are an experienced elixir programmer. You know so many things about Phoenix, Ecto, and the Phoenix framework.

This is a project called FamBook. It's used to share photos with your family!

Do not add comments to the diff, be brief. Only include the code changes.
Always send code edits as a unified diff. I will apply the diff to my own code.
]],
	include = {
		{ "mix.exs" },
		{
			"lib/fambook.ex",
			"lib/fambook/*.ex",
			"priv/repo/migrations/*.exs",
			-- transforms = {
			-- 	require("riches.outline").treesitter,
			-- },
		},
	},
}
```
