-- lazygit integration
-- https://github.com/kdheepak/lazygit.nvim
if vim.fn.executable 'lazygit' ~= 1 then return end

vim.pack.add { 'https://github.com/kdheepak/lazygit.nvim' }

-- Uses ~/Library/Application Support/lazygit/config.yml on macOS (see lazygit --print-config-dir)

-- lazygit.nvim links LazyGitBorder -> Normal by default, which renders as a white border
-- with tokyonight. Match other Neovim floats instead.
local function setup_lazygit_highlights()
  vim.api.nvim_set_hl(0, 'LazyGitBorder', { link = 'FloatBorder' })
  vim.api.nvim_set_hl(0, 'LazyGitFloat', { link = 'NormalFloat' })
end

setup_lazygit_highlights()
local lazygit_augroup = vim.api.nvim_create_augroup('custom-lazygit', { clear = true })
vim.api.nvim_create_autocmd('ColorScheme', {
  group = lazygit_augroup,
  callback = setup_lazygit_highlights,
})
-- Re-apply after lazygit.nvim opens the float (it tries to link border to Normal)
vim.api.nvim_create_autocmd('FileType', {
  group = lazygit_augroup,
  pattern = 'lazygit',
  callback = setup_lazygit_highlights,
})

-- Lazy-load
local function open_lazygit(cmd)
  vim.cmd.packadd 'lazygit.nvim'
  vim.cmd[cmd]()
end

vim.keymap.set('n', '<leader>gg', function() open_lazygit 'LazyGit' end, { desc = 'Open LazyGit' })
vim.keymap.set('n', '<leader>gG', function() open_lazygit 'LazyGitCurrentFile' end, { desc = 'LazyGit (current file repo)' })
