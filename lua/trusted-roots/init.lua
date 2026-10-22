-- Skip Neovim's :trust prompt for project-local config files (.nvim.lua,
-- .nvimrc, .exrc, .nvim/) under directories you list. Everything else still
-- goes through Neovim's normal trust database.
--
-- Anyone who can merge a .nvim.lua into a repo under a listed root gets code
-- execution in your nvim, so list only directories whose repos you trust.

local M = {}

---@class trusted-roots.Config
---@field exrc boolean Turn on 'exrc', which project-local files need at all.
---@field roots string[] Trusted directories (~ is expanded).
---@field files string[] JSON files, each an array of more roots. Read on every
---trust check, so edits apply without a restart. Missing files are skipped.
M.defaults = {
  exrc = true,
  roots = {},
  files = {
    -- Shared, committed with your config.
    vim.fn.stdpath("config") .. "/trusted-roots.json",
    -- This machine only: gitignore it.
    vim.fn.stdpath("config") .. "/trusted-roots.local.json",
  },
}

---@type trusted-roots.Config
M.config = vim.deepcopy(M.defaults)

---All trusted roots: `roots` plus whatever the `files` list.
---@return string[]
function M.roots()
  local roots = vim.list_extend({}, M.config.roots)
  for _, path in ipairs(M.config.files) do
    if vim.uv.fs_stat(path) then
      local ok, decoded = pcall(function()
        return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
      end)
      if ok and vim.islist(decoded) then
        vim.list_extend(roots, decoded)
      else
        -- A typo must not silently turn the trust off, so say so.
        vim.notify(path .. " is not a JSON array of paths, ignoring it", vim.log.levels.WARN)
      end
    end
  end
  return roots
end

---Whether `path` lies under a trusted root. Both sides are resolved through
---symlinks, so a link can't smuggle a file in from outside.
---@param path string
---@return string|nil real The resolved path when trusted.
function M.is_trusted(path)
  local real = vim.uv.fs_realpath(vim.fs.normalize(path))
  if not real then
    return nil
  end
  for _, root in ipairs(M.roots()) do
    local base = vim.uv.fs_realpath(vim.fs.normalize(root))
    if base and vim.startswith(real, base .. "/") then
      return real
    end
  end
end

local secure_read

---@param opts? trusted-roots.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  if M.config.exrc then
    vim.o.exrc = true
  end

  -- Wrap once, even if setup runs again.
  if secure_read then
    return
  end
  secure_read = vim.secure.read
  vim.secure.read = function(path)
    local real = M.is_trusted(path)
    if not real then
      return secure_read(path)
    end
    if vim.fn.isdirectory(real) == 1 then
      return true -- a .nvim/ directory
    end
    local file = assert(io.open(real, "rb"))
    local contents = file:read("*a")
    file:close()
    return contents
  end
end

return M
