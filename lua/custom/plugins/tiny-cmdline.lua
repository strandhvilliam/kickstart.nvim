-- Floating cmdline via tiny-cmdline.nvim (Neovim 0.12+ ui2). See :help ui2
-- Remote: https://github.com/rachartier/tiny-cmdline.nvim
-- Restore vendor/tiny-cmdline.nvim + local vim.pack.add if remote setup regresses.
if vim.fn.has('nvim-0.12') == 0 then
  return
end

vim.o.cmdheight = 0

-- Read by upstream plugin/tiny-cmdline.lua if it auto-inits before our setup().
vim.g.tiny_cmdline = {
  width = { value = '55%', min = 36, max = 72 },
  position = { x = '50%', y = '38%' },
  border = 'rounded',
  native_types = {},
}

local CMDLINE_TITLES = {
  [':'] = ' Command ',
  ['/'] = ' Search ',
  ['?'] = ' Search Backward ',
}

local function cmdline_title()
  return CMDLINE_TITLES[vim.fn.getcmdtype()]
end

local function setup_cmdline_highlights()
  local float_border = vim.api.nvim_get_hl(0, { name = 'FloatBorder', link = false })

  vim.api.nvim_set_hl(0, 'TinyCmdlineNormal', { link = 'NormalFloat' })
  vim.api.nvim_set_hl(0, 'TinyCmdlineBorder', {
    fg = float_border.fg,
  })
  vim.api.nvim_set_hl(0, 'TinyCmdlineTitle', { link = 'FloatTitle' })
end

local function style_cmdline_win()
  local ok, ui2 = pcall(require, 'vim._core.ui2')
  if not ok then
    return
  end

  local win = ui2.wins and ui2.wins.cmd
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  vim.wo[win].winhighlight =
    'Normal:TinyCmdlineNormal,FloatBorder:TinyCmdlineBorder,FloatTitle:TinyCmdlineTitle'
end

local function set_cmdheight_0()
  vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
    vim.o.cmdheight = 0
  end)
end

local function on_reposition()
  style_cmdline_win()
  require('tiny-cmdline').adapters.blink()
end

local tiny_cmdline_opts = {
  width = { value = '55%', min = 36, max = 72 },
  position = { x = '50%', y = '38%' },
  border = 'rounded',
  native_types = {},
  on_reposition = on_reposition,
}

local function reposition_cmdline()
  local tiny = require('tiny-cmdline')
  local config = tiny.config
  local cmdtype = vim.fn.getcmdtype()
  if cmdtype == '' or vim.tbl_contains(config.native_types, cmdtype) then
    return
  end

  local ok, ui2 = pcall(require, 'vim._core.ui2')
  if not ok then
    return
  end

  local win = ui2.wins and ui2.wins.cmd
  if not win or not vim.api.nvim_win_is_valid(win) then
    return
  end

  local border = config.border or 'rounded'
  local b = border == 'none' and 0 or 1
  local cols, lines = vim.o.columns, vim.o.lines

  local function parse_dimension(value, available)
    if type(value) == 'string' then
      return math.floor(available * tonumber(value:match('^(%d+)%%$')) / 100)
    end
    return math.floor(value)
  end

  local width = math.max(
    config.width.min,
    math.min(config.width.max, parse_dimension(config.width.value, cols))
  )
  width = math.min(width, cols - 4)

  local content_height = math.max(1, vim.api.nvim_win_get_height(win))
  local row = math.max(0, parse_dimension(config.position.y, lines - content_height - b * 2))
  local col = math.max(0, parse_dimension(config.position.x, cols - width - b * 2))
  local title = cmdline_title()

  pcall(vim.api.nvim_win_set_config, win, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    border = border,
    hide = false,
    title = title,
    title_pos = title and 'center' or nil,
  })

  vim.g.ui_cmdline_pos = { row + content_height + b * 2, col + b + config.menu_col_offset }
  style_cmdline_win()
  if config.on_reposition then
    config.on_reposition()
  end
end

local function force_ui2_cmdline()
  local ok, cmdline_mod = pcall(require, 'vim._core.ui2.cmdline')
  if not ok then
    return
  end

  local firstc = vim.fn.getcmdtype()
  if firstc == '' then
    return
  end

  local line = vim.fn.getcmdline()
  local content = line ~= '' and { { 0, line } } or {}
  local ui_cmdline = require('vim._core.ui2.cmdline')
  local level = ui_cmdline.level == 0 and 1 or ui_cmdline.level + 1

  cmdline_mod.cmdline_show(content, vim.fn.strchars(line), firstc, '', 0, level, 0)
end

local function on_cmdline_enter()
  set_cmdheight_0()
  force_ui2_cmdline()
  reposition_cmdline()
  vim.cmd.redraw()
end

local cmdline_augroup = vim.api.nvim_create_augroup('custom-tiny-cmdline', { clear = true })
local hooks_installed = false

local function install_cmdline_hooks()
  if hooks_installed then
    return
  end

  local cmdline = require('vim._core.ui2.cmdline')
  local show_orig = cmdline.cmdline_show
  cmdline.cmdline_show = function(...)
    local r = show_orig(...)
    -- ui2 bumps cmdheight to 1 on every keystroke (including / search); reset
    -- immediately so the legacy bottom cmdline row never appears.
    set_cmdheight_0()
    reposition_cmdline()
    return r
  end

  vim.api.nvim_create_autocmd('OptionSet', {
    group = cmdline_augroup,
    pattern = 'cmdheight',
    callback = function()
      if vim.fn.getcmdtype() == '' then
        return
      end
      set_cmdheight_0()
      reposition_cmdline()
    end,
  })

  vim.api.nvim_create_autocmd('CmdlineEnter', {
    group = cmdline_augroup,
    callback = on_cmdline_enter,
  })

  hooks_installed = true
end

local initialized = false
local function init_floating_cmdline()
  if initialized or #vim.api.nvim_list_uis() == 0 then
    return
  end

  setup_cmdline_highlights()
  require('vim._core.ui2').enable()

  local tiny = require('tiny-cmdline')
  if tiny._initialized then
    tiny.config = vim.tbl_deep_extend('force', tiny.config, tiny_cmdline_opts)
  else
    tiny.setup(tiny_cmdline_opts)
  end

  install_cmdline_hooks()
  initialized = true
end

-- Register before pack.add so we run ahead of the plugin's UIEnter autocmd.
vim.api.nvim_create_autocmd({ 'VimEnter', 'UIEnter' }, {
  once = true,
  callback = function()
    vim.schedule(init_floating_cmdline)
  end,
})

vim.pack.add { 'https://github.com/rachartier/tiny-cmdline.nvim' }

vim.api.nvim_create_autocmd('ColorScheme', {
  group = cmdline_augroup,
  callback = setup_cmdline_highlights,
})

vim.api.nvim_create_autocmd({ 'CmdlineEnter', 'FileType' }, {
  group = cmdline_augroup,
  pattern = { '*', 'cmd' },
  callback = function()
    vim.schedule(function()
      style_cmdline_win()
      reposition_cmdline()
    end)
  end,
})


pcall(vim.pack.del, { 'noice.nvim' })
