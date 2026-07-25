-- lazygit integration
-- https://github.com/kdheepak/lazygit.nvim
-- Theme + nvim-remote integration inspired by snacks.nvim:
-- https://github.com/folke/snacks.nvim/blob/main/docs/lazygit.md
--
-- Every entry point here builds its own command and owns its own window
-- lifecycle. The plugin's `lazygit.lazygit()` et al are deliberately unused:
-- they keep launch state in globals (LAZYGIT_LOADED) that a non-zero exit
-- leaves stale, which blocks all later launches until Neovim restarts.
if vim.fn.executable 'lazygit' ~= 1 then return end

vim.pack.add { 'https://github.com/kdheepak/lazygit.nvim' }

local generated_config_path = vim.fs.normalize(vim.fn.stdpath 'cache' .. '/lazygit-theme.yml')

---@class lazygit.Color
---@field fg? string
---@field bg? string
---@field bold? boolean

--- Numeric keys are ANSI palette slots lazygit uses directly; string keys are
--- lazygit `gui.theme` options. Values name the Neovim highlight to sample.
---@type table<number|string, lazygit.Color>
local lazygit_theme = {
  [241] = { fg = 'Special' },
  activeBorderColor = { fg = 'Function', bold = true },
  cherryPickedCommitBgColor = { fg = 'Identifier' },
  cherryPickedCommitFgColor = { fg = 'Function' },
  defaultFgColor = { fg = 'Normal' },
  inactiveBorderColor = { fg = 'Comment' },
  optionsTextColor = { fg = 'Function' },
  searchingActiveBorderColor = { fg = 'MatchParen', bold = true },
  selectedLineBgColor = { bg = 'Visual' },
  unstagedChangesColor = { fg = 'DiagnosticError' },
}

--- Defaults that make lazygit cooperate with Neovim. lazygit unmarshals each
--- `-ucf` file onto the same config struct in order, so later files win per
--- key; this generated file is passed first so the user's own config.yml stays
--- authoritative for anything it sets explicitly.
local lazygit_config = {
  os = {
    editPreset = 'nvim-remote',
    promptToReturnFromSubprocess = false,
  },
  gui = { nerdFontsVersion = '3' },
}

---@param color lazygit.Color
---@return string[]? -- nil when nothing resolved, so lazygit keeps its default
local function get_color(color)
  local values = {}
  for _, channel in ipairs { 'fg', 'bg' } do
    local hl_name = color[channel]
    if hl_name then
      local hl = vim.api.nvim_get_hl(0, { name = hl_name, link = false })
      if hl[channel] then values[#values + 1] = ('#%06x'):format(hl[channel]) end
    end
  end

  -- Emitting a bare `bold` (or an empty list) would override lazygit's default
  -- for this key with something colorless, so require a resolved color.
  if not values[1] then return nil end

  if color.bold then values[#values + 1] = 'bold' end
  return values
end

---@param value string|boolean|number
---@return string
local function yaml_val(value)
  if type(value) == 'boolean' or type(value) == 'number' then return tostring(value) end
  -- JSON strings are valid YAML double-quoted scalars and escape correctly.
  return vim.json.encode(value)
end

---@param tbl table
---@param indent? integer
---@return string[]
local function to_yaml(tbl, indent)
  indent = indent or 0
  local pad = string.rep(' ', indent)

  -- Sorted so the output is byte-stable and we can skip no-op writes.
  local keys = vim.tbl_keys(tbl)
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

  local lines = {}
  for _, key in ipairs(keys) do
    local value = tbl[key]
    if type(value) == 'table' then
      lines[#lines + 1] = pad .. key .. ':'
      if vim.islist(value) then
        for _, item in ipairs(value) do
          lines[#lines + 1] = pad .. '  - ' .. yaml_val(item)
        end
      else
        vim.list_extend(lines, to_yaml(value, indent + 2))
      end
    else
      lines[#lines + 1] = pad .. key .. ': ' .. yaml_val(value)
    end
  end
  return lines
end

local config_dirty = true

--- Regenerate the config lazygit reads.
---@return boolean ok -- lazygit refuses to start if a `-ucf` file is missing
local function write_lazygit_config()
  ---@type table<string, string[]>
  local theme = {}
  for key, color in pairs(lazygit_theme) do
    if type(key) ~= 'number' then theme[key] = get_color(color) end
  end

  local lines = to_yaml(vim.tbl_deep_extend('force', { gui = { theme = theme } }, lazygit_config))

  local unchanged = vim.fn.filereadable(generated_config_path) == 1 and vim.deep_equal(vim.fn.readfile(generated_config_path), lines)

  if not unchanged and vim.fn.writefile(lines, generated_config_path) ~= 0 then
    vim.notify('lazygit: could not write ' .. generated_config_path, vim.log.levels.ERROR)
    return false
  end

  config_dirty = false
  return true
end

--- Push palette overrides to the host terminal. This mutates the terminal
--- emulator for the rest of its life (it outlives Neovim and applies to every
--- other program in the pane), so it only runs when actually launching lazygit
--- rather than at startup or on every :colorscheme.
local function apply_terminal_palette()
  for key, color in pairs(lazygit_theme) do
    if type(key) == 'number' then
      local value = get_color(color)
      if value then pcall(io.write, ('\27]4;%d;%s\7'):format(key, value[1])) end
    end
  end
end

---@type string|false|nil -- false once we know `lazygit -cd` failed
local config_dir

---@return string? -- the user's own config.yml, whether or not it exists yet
local function user_config_path()
  if config_dir == nil then
    local out = vim.fn.system { 'lazygit', '-cd' }
    config_dir = vim.v.shell_error == 0 and vim.trim(out) or false
  end
  return config_dir and vim.fs.normalize(config_dir .. '/config.yml') or nil
end

---@return string[]
local function config_paths()
  local paths = { generated_config_path }
  local user_config = user_config_path()
  -- Only pass it if it exists: a missing -ucf file is a hard startup error.
  if user_config and vim.uv.fs_stat(user_config) then paths[#paths + 1] = user_config end
  return paths
end

---@param args string[]
---@return string[]
local function build_lazygit_cmd(args)
  local cmd = { 'lazygit' }
  vim.list_extend(cmd, args)
  vim.list_extend(cmd, { '-ucf', table.concat(config_paths(), ',') })

  if vim.env.GIT_DIR and vim.env.GIT_WORK_TREE then vim.list_extend(cmd, { '-w', vim.env.GIT_WORK_TREE, '-g', vim.env.GIT_DIR }) end

  return cmd
end

local function on_lazygit_exit()
  vim.cmd 'silent! checktime'
  pcall(function() require('gitsigns').refresh() end)
end

-- lazygit.nvim links LazyGitBorder -> Normal (with `default = true`, so an
-- explicit set here wins permanently and needs no re-apply on FileType).
local function setup_lazygit_highlights()
  vim.api.nvim_set_hl(0, 'LazyGitBorder', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'LazyGitFloat', { link = 'NormalFloat' })
end

setup_lazygit_highlights()

local prev_win = -1
local win = -1
local buffer = -1

local function close_lazygit_window()
  if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  if vim.api.nvim_buf_is_valid(buffer) then vim.api.nvim_buf_delete(buffer, { force = true }) end

  -- Restore focus only if the window we launched from still exists; the float
  -- must be torn down either way.
  if vim.api.nvim_win_is_valid(prev_win) then vim.api.nvim_set_current_win(prev_win) end

  prev_win, win, buffer = -1, -1, -1

  -- The plugin caches the float in globals and skips launching when it thinks
  -- one is already open. Clear them so :LazyGit stays usable too.
  _G.LAZYGIT_BUFFER = nil
  _G.LAZYGIT_LOADED = false
  vim.g.lazygit_opened = 0
end

---@param args string[]
local function run_lazygit(args)
  -- Already running: focus it rather than stacking a second float and orphaning
  -- the first (the args of the new invocation are ignored, as they would be by
  -- the plugin's own reuse check).
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
    vim.cmd 'startinsert'
    return
  end

  if config_dirty and not write_lazygit_config() then return end
  apply_terminal_palette()

  prev_win = vim.api.nvim_get_current_win()
  win, buffer = require('lazygit.window').open_floating_window()

  local cmd = build_lazygit_cmd(args)

  vim.schedule(function()
    vim.fn.jobstart(cmd, {
      term = true,
      on_exit = function(_, code)
        -- Always tear the float down. Leaving a dead terminal floating strands
        -- the window and makes every later launch a no-op.
        close_lazygit_window()
        if code ~= 0 then vim.notify(('lazygit exited with code %d'):format(code), vim.log.levels.WARN) end
        on_lazygit_exit()
      end,
    })
    vim.cmd 'startinsert'
  end)
end

--- Git root for the current buffer, falling back to cwd for terminal and
--- unnamed buffers.
---@return string?
local function current_git_root()
  local dir = (vim.bo.buftype ~= '' or vim.api.nvim_buf_get_name(0) == '') and vim.fn.getcwd() or vim.fn.expand '%:p:h'

  local root = require('lazygit.utils').get_root(dir)
  if type(root) ~= 'string' or root == '' or root:match '^fatal:' then return nil end
  return root
end

---@alias LazygitMode 'repo' | 'current_file' | 'filter_current_file' | 'log' | 'log_current_file' | 'config'

---@param mode LazygitMode
local function open_lazygit(mode)
  if mode == 'config' then
    local path = user_config_path()
    if not path then
      vim.notify('lazygit: could not resolve the config directory', vim.log.levels.ERROR)
      return
    end
    -- Only the user's config is worth editing; ours is regenerated from the
    -- colorscheme and would be overwritten.
    require('lazygit.utils').open_or_create_config(path)
    return
  end

  local args = {}

  if mode == 'repo' then
    args = {} -- lazygit picks up the cwd
  elseif mode == 'log' then
    args = { 'log' }
  else
    local root = current_git_root()
    if not root then
      vim.notify('Not inside a git repository', vim.log.levels.WARN)
      return
    end

    if mode == 'current_file' then
      args = { '-p', root }
    else
      local file = vim.api.nvim_buf_get_name(0)
      if file == '' or vim.bo.buftype ~= '' then
        vim.notify('No file to filter on', vim.log.levels.WARN)
        return
      end

      -- lazygit filters via `git log -- <path>` from the repo root, so pass a
      -- relative path: it matches what the UI displays.
      local relative = vim.fs.relpath(root, file) or file
      args = { '-f', relative, '-p', root }
      if mode == 'log_current_file' then table.insert(args, 1, 'log') end
    end
  end

  run_lazygit(args)
end

-- Read by lazygit.nvim's window helper and by its gitcommit ftplugin. Setting
-- use_neovim_remote = 0 keeps that ftplugin's nvr hook from competing with the
-- nvim-remote editPreset we generate above.
vim.g.lazygit_use_neovim_remote = 0
vim.g.lazygit_floating_window_border_chars = 'rounded'

local lazygit_augroup = vim.api.nvim_create_augroup('custom-lazygit', { clear = true })

vim.api.nvim_create_autocmd('ColorScheme', {
  group = lazygit_augroup,
  callback = function()
    -- Regenerate on next open rather than now: writing here would also re-emit
    -- the terminal palette escape on every colorscheme change.
    config_dirty = true
    setup_lazygit_highlights()
  end,
})

---@type table<string, LazygitMode>
local commands = {
  LazyGit = 'repo',
  LazyGitCurrentFile = 'current_file',
  LazyGitFilterCurrentFile = 'filter_current_file',
  LazyGitLog = 'log',
  LazyGitConfig = 'config',
}

-- plugin/lazygit.vim is sourced after init.lua, so its :command! definitions
-- would clobber ours. Claim them once the runtime has settled so the commands
-- and the keymaps below share a single code path.
vim.api.nvim_create_autocmd('VimEnter', {
  group = lazygit_augroup,
  once = true,
  callback = function()
    for name, mode in pairs(commands) do
      vim.api.nvim_create_user_command(name, function() open_lazygit(mode) end, { desc = 'lazygit: ' .. mode })
    end
  end,
})

---@type table<string, [LazygitMode, string]>
local keymaps = {
  ['<leader>gg'] = { 'repo', '[G]it: Lazy[G]it' },
  ['<leader>gG'] = { 'current_file', '[G]it: Lazy[G]it (current file repo)' },
  ['<leader>gf'] = { 'filter_current_file', '[G]it: Lazy[G]it [f]ilter current file' },
  ['<leader>gl'] = { 'log', '[G]it: Lazy[G]it log' },
  ['<leader>gL'] = { 'log_current_file', '[G]it: Lazy[G]it log (current file)' },
  ['<leader>gC'] = { 'config', '[G]it: Lazy[G]it [C]onfig' },
}

for lhs, spec in pairs(keymaps) do
  vim.keymap.set('n', lhs, function() open_lazygit(spec[1]) end, { desc = spec[2] })
end
