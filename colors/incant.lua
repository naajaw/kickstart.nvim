-- Entry point for the "incant" colorscheme.
-- Neovim automatically scans the colors/ directory in your runtimepath,
-- so this file is found when you do :colorscheme incant or set
-- colorscheme = "incant" in your LazyVim plugin spec.

-- Reset any previously active colorscheme to avoid bleed-through.
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "incant"
vim.o.termguicolors = true -- Required: enables 24-bit hex color support in terminals.

require("incant").setup()
