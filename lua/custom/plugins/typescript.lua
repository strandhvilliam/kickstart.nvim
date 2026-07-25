-- TypeScript: monorepo root_dir and workspace TypeScript SDK discovery

---@param bufnr integer
---@return string|nil
local function find_typescript_sdk(bufnr)
  local roots = {
    vim.fs.root(bufnr, { 'tsconfig.json', 'package.json' }),
    vim.fs.root(bufnr, { 'pnpm-lock.yaml', 'package-lock.json', 'yarn.lock' }),
  }

  for _, root in ipairs(roots) do
    if root then
      local tsdk = vim.fs.joinpath(root, 'node_modules/typescript/lib')
      if vim.fn.isdirectory(tsdk) == 1 then
        return tsdk
      end
    end
  end
end

---@param bufnr integer
---@param on_dir fun(dir: string)
local function ts_ls_root_dir(bufnr, on_dir)
  local path = vim.api.nvim_buf_get_name(bufnr)

  local package_root = vim.fs.root(bufnr, { 'tsconfig.json', 'package.json' })
  if package_root and path:find('/clients/apps/') then
    on_dir(package_root)
    return
  end

  local root_markers = { 'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', 'bun.lockb', 'bun.lock' }
  root_markers = vim.fn.has('nvim-0.11.3') == 1 and { root_markers, { '.git' } }
    or vim.list_extend(root_markers, { '.git' })

  on_dir(vim.fs.root(bufnr, root_markers) or vim.fn.getcwd())
end

vim.lsp.config('ts_ls', {
  root_dir = ts_ls_root_dir,
  settings = {
    typescript = {
      preferences = {
        autoImportFileExcludePatterns = { '**/repos/**' },
      },
    },
    javascript = {
      preferences = {
        autoImportFileExcludePatterns = { '**/repos/**' },
      },
    },
  },
})

vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('custom-typescript-lsp', { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= 'ts_ls' then
      return
    end

    local tsdk = find_typescript_sdk(event.buf)
    if not tsdk then
      return
    end

    client.config.settings = vim.tbl_deep_extend('force', client.config.settings or {}, {
      typescript = { tsdk = tsdk },
    })
    client:notify('workspace/didChangeConfiguration', { settings = client.config.settings })
  end,
})
