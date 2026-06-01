-- Add indentation guides even on blank lines

-- Enable `lukas-reineke/indent-blankline.nvim`
-- See `:help ibl`
vim.pack.add { 'https://github.com/lukas-reineke/indent-blankline.nvim' }

local hooks = require 'ibl.hooks'

local function setup_indent_highlights()
  -- Comment (#8b949e) is brighter than the plugin default; use a darker gray instead.
  local dim = { fg = '#30363d', nocombine = true }
  vim.api.nvim_set_hl(0, 'IblIndent', dim)
  vim.api.nvim_set_hl(0, 'IblWhitespace', dim)
  vim.api.nvim_set_hl(0, 'IblScope', dim)
end

hooks.register(hooks.type.HIGHLIGHT_SETUP, setup_indent_highlights)

vim.api.nvim_create_autocmd('ColorScheme', {
  callback = function()
    setup_indent_highlights()
    require('ibl').refresh()
  end,
})

require('ibl').setup {}
