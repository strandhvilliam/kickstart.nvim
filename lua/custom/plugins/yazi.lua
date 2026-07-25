-- yazi file manager
-- https://github.com/mikavilpas/yazi.nvim

-- `ya` is the sidecar CLI yazi.nvim talks to; both are required. Bail before
-- setup() runs, because open_for_directories makes yazi.nvim disable netrw's
-- directory handling (`autocmd! FileExplorer *`) whether or not yazi is
-- actually usable -- which would otherwise leave no file explorer at all.
if vim.fn.executable 'yazi' ~= 1 or vim.fn.executable 'ya' ~= 1 then return end

vim.pack.add {
  { src = 'https://github.com/mikavilpas/yazi.nvim', version = vim.version.range '*' },
}

-- netrw is deliberately left enabled. yazi.nvim already takes over directory
-- opens on its own, and netrw still supplies :Explore plus the scp://-style
-- remote paths that yazi explicitly declines to hijack.

-- Return the visible yazi floating window and its buffer, if any. Scoped across
-- tabpages to match find_yazi_buf: otherwise a yazi opened in another tab is
-- invisible here, and close_yazi_session would delete its buffer out from
-- under it.
local function find_yazi_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'yazi' then return win, buf end
    end
  end
end

-- Return a yazi buffer that may still exist after the window was closed
local function find_yazi_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == 'yazi' then return buf end
  end
end

-- Fully close yazi so the next open always uses the current buffer's file.
-- Killing the terminal buffer is what ends the yazi process; yazi.nvim's own
-- on_exit still runs from there, reaping `ya` and recording the last hovered
-- file, so :Yazi toggle keeps working.
local function close_yazi_session()
  local win, buf = find_yazi_win()
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end

  buf = buf or find_yazi_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
end

-- Open yazi at the current file (visual mode: use the selected path)
local function open_yazi_at_current_file() require('yazi').yazi() end

-- Close if open, else open at current file (always follows the buffer you're in)
local function toggle_yazi_at_current_file()
  local was_open = find_yazi_win() ~= nil

  -- Run unconditionally: a yazi buffer can outlive its window, and leaving it
  -- around would make the next open resume there instead of the current file.
  close_yazi_session()

  if not was_open then open_yazi_at_current_file() end
end

-- Bind the toggle inside the yazi terminal so it works while yazi is focused.
-- Only the Cmd chord: <leader> expands to <Space> at definition time in any
-- mode, and Space is yazi's own select-toggle. Without a super-capable
-- terminal, quit yazi with its native `q` instead.
local function bind_yazi_terminal_keymaps(event)
  vim.keymap.set('t', '<D-e>', toggle_yazi_at_current_file, {
    buffer = event.buf,
    desc = 'Toggle yazi at current file',
  })
end

require('yazi').setup {
  -- nvim . / :edit dir/ opens yazi instead of netrw
  open_for_directories = true,
  -- The float border is left at yazi.nvim's default, which already follows
  -- 'winborder' when it is set and falls back to 'rounded' when it is not.
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

local yazi_augroup = vim.api.nvim_create_augroup('custom-yazi', { clear = true })

vim.api.nvim_create_autocmd('FileType', {
  group = yazi_augroup,
  pattern = 'yazi',
  callback = bind_yazi_terminal_keymaps,
})

-- yazi.nvim clears netrw's FileExplorer autocmds during setup, but netrw is
-- packadd'ed from plugin/netrwPlugin.vim *after* init.lua and registers them
-- again -- which leaves a stray netrw buffer behind on every directory open.
-- Clear them once more, after netrw has loaded. Only the directory hijack goes
-- away; :Explore and netrw's remote-path handling live elsewhere.
vim.api.nvim_create_autocmd('VimEnter', {
  group = yazi_augroup,
  once = true,
  callback = function() vim.cmd 'silent! autocmd! FileExplorer *' end,
})

-- <leader>-  open at current file (visual: use selected path)
vim.keymap.set({ 'n', 'v' }, '<leader>-', open_yazi_at_current_file, { desc = 'Open yazi at current file' })

-- <leader>cw  open at Neovim :pwd
vim.keymap.set('n', '<leader>cw', '<cmd>Yazi cwd<cr>', { desc = 'Open yazi in working directory' })

-- Cmd+e / <leader>e  toggle off if open; open fresh at current file (updates
-- after telescope jumps, etc.). <leader>e is the fallback for terminals that
-- don't encode the super modifier -- Cmd+e never arrives over plain SSH.
vim.keymap.set({ 'n', 'v' }, '<D-e>', toggle_yazi_at_current_file, { desc = 'Toggle yazi at current file' })
vim.keymap.set({ 'n', 'v' }, '<leader>e', toggle_yazi_at_current_file, { desc = 'Toggl[e] yazi at current file' })

-- <C-Up>  reopen last session at last hovered file
vim.keymap.set('n', '<C-Up>', '<cmd>Yazi toggle<cr>', { desc = 'Resume last yazi session' })
