-- lazygit integration
-- https://github.com/kdheepak/lazygit.nvim
if vim.fn.executable 'lazygit' ~= 1 then return end

vim.pack.add { 'https://github.com/kdheepak/lazygit.nvim' }

-- Lazy-load
local function open_lazygit(cmd)
  vim.cmd.packadd 'lazygit.nvim'
  vim.cmd[cmd]()
end

vim.keymap.set('n', '<leader>lg', function() open_lazygit 'LazyGit' end, { desc = 'Open LazyGit' })
vim.keymap.set('n', '<leader>lG', function() open_lazygit 'LazyGitCurrentFile' end, { desc = 'LazyGit (current file repo)' })
