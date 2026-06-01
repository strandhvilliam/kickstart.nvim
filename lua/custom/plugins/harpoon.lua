-- Harpoon 2: fast navigation between pinned files
-- https://github.com/ThePrimeagen/harpoon/tree/harpoon2

vim.pack.add {
  { src = 'https://github.com/ThePrimeagen/harpoon', version = 'harpoon2' },
}

local harpoon = require 'harpoon'

harpoon:setup()

vim.keymap.set('n', 'Q', function() harpoon:list():add() end, { desc = 'Harpoon: add file' })
vim.keymap.set('n', 'q', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = 'Harpoon: toggle menu' })

for i = 1, 4 do
  vim.keymap.set('n', '<C-' .. i .. '>', function() harpoon:list():select(i) end, { desc = 'Harpoon: go to file ' .. i })
end

vim.keymap.set('n', '<C-[>', function() harpoon:list():prev() end, { desc = 'Harpoon: previous file' })
vim.keymap.set('n', '<C-]>', function() harpoon:list():next() end, { desc = 'Harpoon: next file' })

