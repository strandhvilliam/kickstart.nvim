-- yazi file manager
-- https://github.com/mikavilpas/yazi.nvim

-- Disable netrw; yazi handles directory opens instead
vim.g.loaded_netrwPlugin = 1

vim.pack.add {
  { src = 'https://github.com/mikavilpas/yazi.nvim', version = vim.version.range '*' },
}

-- Return the visible yazi floating window and its buffer, if any
local function find_yazi_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'yazi' then
        return win, buf
      end
    end
  end
end

-- Return a yazi buffer that may still exist after the window was closed
local function find_yazi_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'yazi' then
      return buf
    end
  end
end

-- Fully close yazi so the next open always uses the current buffer's file
local function close_yazi_session()
  local win, buf = find_yazi_win()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  buf = buf or find_yazi_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

-- Open yazi at the current file (visual mode: use the selected path)
local function open_yazi_at_current_file()
  require('yazi').yazi()
end

-- Cmd+e: close if open, else open at current file (always follows the buffer you're in)
local function toggle_yazi_at_current_file()
  if find_yazi_win() then
    close_yazi_session()
    return
  end

  close_yazi_session()
  open_yazi_at_current_file()
end

-- Bind Cmd+e inside the yazi terminal so it works while yazi is focused
local function bind_yazi_terminal_keymaps(event)
  vim.keymap.set('t', '<D-e>', toggle_yazi_at_current_file, {
    buffer = event.buf,
    desc = 'Toggle yazi at current file',
  })
end

require('yazi').setup {
  -- nvim . / :edit dir/ opens yazi instead of netrw
  open_for_directories = true,
  yazi_floating_window_border = 'rounded',
  set_keymappings_function = function(yazi_buffer, config, context)
    local helpers = require 'yazi.keybinding_helpers'
    local utils = require 'yazi.utils'

    vim.keymap.set('t', '<C-f>', function()
      helpers.select_current_file_and_close_yazi(config, {
        api = context.api,
        on_file_opened = function(chosen_file)
          local search_dir = utils.dir_of(chosen_file):make_relative(vim.uv.cwd())
          require('telescope.builtin').find_files {
            cwd = search_dir,
            prompt_title = 'Files in ' .. search_dir,
          }
        end,
        on_multiple_files_opened = function(chosen_files)
          local plenary_path = require 'plenary.path'
          local search_dirs = {}
          for _, path in ipairs(chosen_files) do
            search_dirs[#search_dirs + 1] = plenary_path:new(path):make_relative(vim.uv.cwd())
          end
          require('telescope.builtin').find_files {
            prompt_title = string.format('Files in %d paths', #search_dirs),
            search_dirs = search_dirs,
          }
        end,
      })
    end, { buffer = yazi_buffer, desc = 'Telescope find files in directory' })
  end,
}

vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('custom-yazi', { clear = true }),
  pattern = 'yazi',
  callback = bind_yazi_terminal_keymaps,
})

-- <leader>-  open at current file (visual: use selected path)
vim.keymap.set({ 'n', 'v' }, '<leader>-', open_yazi_at_current_file, { desc = 'Open yazi at current file' })

-- <leader>cw  open at Neovim :pwd
vim.keymap.set('n', '<leader>cw', '<cmd>Yazi cwd<cr>', { desc = 'Open yazi in working directory' })

-- Cmd+e  toggle off if open; open fresh at current file (updates after telescope jumps, etc.)
vim.keymap.set({ 'n', 'v' }, '<D-e>', toggle_yazi_at_current_file, { desc = 'Toggle yazi at current file' })

-- <C-Up>  reopen last session at last hovered file
vim.keymap.set('n', '<C-Up>', '<cmd>Yazi toggle<cr>', { desc = 'Resume last yazi session' })
