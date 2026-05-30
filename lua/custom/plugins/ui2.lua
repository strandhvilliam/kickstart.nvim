-- Neovim 0.12+ experimental cmdline/message UI. See :help ui2
local enabled = false

local function enable_ui2()
  if enabled or #vim.api.nvim_list_uis() == 0 then
    return
  end
  require('vim._core.ui2').enable()
  enabled = true
end

local function schedule_enable()
  vim.schedule(enable_ui2)
end

-- Must run after the UI attaches; calling during init is too early and no-ops.
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = schedule_enable,
})

vim.api.nvim_create_autocmd('UIEnter', {
  once = true,
  callback = schedule_enable,
})

