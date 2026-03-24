return {
  {
    -- "dir" tells Lazy to load from your local config rather than cloning a repo.
    name = "incant",
    dir = vim.fn.stdpath("config"), -- resolves to ~/.config/nvim
    lazy = false,
    priority = 1000,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "incant", -- matches vim.g.colors_name in colors/mytheme.lua
    },
  },
}
