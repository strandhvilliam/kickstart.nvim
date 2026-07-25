-- Python: venv discovery for basedpyright, analysis settings, ruff lint hooks

---@param root_dir string|nil
---@param bufnr integer
---@return string|nil
local function find_python_interpreter(root_dir, bufnr)
  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  if bufpath ~= '' then
    local venvs = vim.fs.find('.venv', { path = bufpath, upward = true, type = 'dir', limit = 5 })
    for _, venv in ipairs(venvs) do
      local python = vim.fs.joinpath(venv, 'bin', 'python')
      if vim.fn.filereadable(python) == 1 then return python end
    end
  end

  if not root_dir then return nil end

  for _, rel in ipairs({ '.venv', 'server/.venv', 'backend/.venv', 'api/.venv' }) do
    local python = vim.fs.joinpath(root_dir, rel, 'bin', 'python')
    if vim.fn.filereadable(python) == 1 then return python end
  end
end

---@param client vim.lsp.Client
---@param bufnr integer
local function set_basedpyright_python_path(client, bufnr)
  local python = find_python_interpreter(client.root_dir, bufnr)
  if not python then return end

  client.config.settings = vim.tbl_deep_extend('force', client.config.settings or {}, {
    python = { pythonPath = python },
  })
  if client.settings then
    client.settings.python = vim.tbl_deep_extend('force', client.settings.python or {}, {
      pythonPath = python,
    })
  end
  client:notify('workspace/didChangeConfiguration', { settings = nil })
end

vim.lsp.config('basedpyright', {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = 'basic',
        diagnosticMode = 'openFilesOnly',
      },
    },
  },
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('custom-python-lsp', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= 'basedpyright' then return end
    set_basedpyright_python_path(client, event.buf)
  end,
})
