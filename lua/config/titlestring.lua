local cwd = vim.fn.getcwd()

local title
if vim.fn.argc() == 1 then
  local arg = vim.fn.argv(0)
  if vim.fn.filereadable(arg) == 1 then
    local full = vim.fn.fnamemodify(arg, ":p")
    local rel = full:sub(#cwd + 2)
    local root = vim.fn.fnamemodify(cwd, ":t")
    title = root .. "/" .. rel
  end
end

if not title then
  local parent = vim.fn.fnamemodify(cwd, ":h:t")
  local dir = vim.fn.fnamemodify(cwd, ":t")
  title = parent .. "/" .. dir
end

return function()
  return title
end
