# nvim-trusted-roots

Neovim can run project-local config (`.nvim.lua`, `.nvimrc`, `.exrc`) when
`'exrc'` is on, but it asks you to `:trust` every such file, and again after
every change to it. If all your own and your team's repos live under a couple
of directories, that prompt is noise.

This plugin skips the prompt for files under directories you list. Files
anywhere else still go through Neovim's normal trust check.

> [!WARNING]
> Anyone who can merge a `.nvim.lua` into a repo under a trusted root can run
> code in your Neovim. List only directories whose repos you trust.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "SpechtLabs/nvim-trusted-roots",
  lazy = false, -- must be set up before Neovim reads the project files
  opts = {
    roots = { "~/src/github.com/my-org" },
  },
}
```

Neovim reads project-local files after your config, so a plugin that loads at
startup is in time. Don't lazy-load it.

## Configure

The values shown are the defaults:

```lua
opts = {
  -- Turn on 'exrc'. Project-local files aren't read at all without it.
  exrc = true,
  -- Trusted directories. ~ is expanded.
  roots = {},
  -- JSON files, each an array of more roots. Missing files are skipped.
  files = {
    vim.fn.stdpath("config") .. "/trusted-roots.json",
    vim.fn.stdpath("config") .. "/trusted-roots.local.json",
  },
}
```

The two files let you keep roots apart. `trusted-roots.json` is committed with
your dotfiles. `trusted-roots.local.json` is for one machine only, so put it in
your `.gitignore`. For example:

```json
["~/src/gh/spechtlabs", "~/src/gh/cedi"]
```

The files are read on every trust check, so an edit takes effect without a
restart. A file that isn't a JSON array is skipped with a warning
rather than ignored silently.

## How it works

`setup` wraps `vim.secure.read`, the function Neovim calls before it runs a
project-local file. For a path under a trusted root, the wrapper returns the
file's contents (or `true` for a `.nvim/` directory) without prompting. For
any other path, it calls the original.

Both the path and the roots are resolved through symlinks first. A symlink
inside a trusted root that points outside it is not trusted, and
`~/src/foo-bar` doesn't match a root of `~/src/foo`.

## Development

```sh
mise run check   # stylua --check and the headless tests
```

## License

[Apache 2.0](LICENSE)
