-- nvim --headless -u NONE -l tests/run.lua (or `mise run test`)
vim.opt.rtp:prepend(".")

local tmp = vim.uv.fs_realpath(vim.fn.tempname():match("^(.*)/")) .. "/trusted-roots-test-" .. vim.uv.getpid()
local function write(path, text)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(vim.split(text, "\n"), path)
end

write(tmp .. "/trusted/repo/.nvim.lua", "-- trusted")
write(tmp .. "/trusted-sibling/repo/.nvim.lua", "-- prefix trap")
write(tmp .. "/untrusted/.nvim.lua", "-- untrusted")
vim.fn.mkdir(tmp .. "/trusted/repo/.nvim", "p")
write(tmp .. "/roots.json", vim.json.encode({ tmp .. "/from-json" }))
write(tmp .. "/from-json/.nvim.lua", "-- from json")
write(tmp .. "/broken.json", "{ not json")
vim.uv.fs_symlink(tmp .. "/untrusted/.nvim.lua", tmp .. "/trusted/repo/link.lua")

-- Stand-in for Neovim's own check, which would prompt.
vim.secure.read = function()
  return "FALLBACK"
end

local warnings = {}
vim.notify = function(msg)
  table.insert(warnings, msg)
end

local tr = require("trusted-roots")
vim.o.exrc = false
tr.setup({ roots = { tmp .. "/trusted" }, files = { tmp .. "/roots.json", tmp .. "/missing.json" } })

assert(vim.o.exrc, "setup turns on 'exrc'")
assert(vim.secure.read(tmp .. "/trusted/repo/.nvim.lua") == "-- trusted\n", "file under a root is read")
assert(vim.secure.read(tmp .. "/trusted/repo/.nvim") == true, "directory under a root is trusted")
assert(vim.secure.read(tmp .. "/from-json/.nvim.lua") == "-- from json\n", "roots from a JSON file count")
assert(vim.secure.read(tmp .. "/untrusted/.nvim.lua") == "FALLBACK", "file outside the roots falls back")
assert(vim.secure.read(tmp .. "/trusted-sibling/repo/.nvim.lua") == "FALLBACK", "a shared name prefix is no match")
assert(vim.secure.read(tmp .. "/trusted/repo/link.lua") == "FALLBACK", "a symlink out of a root falls back")
assert(#warnings == 0, "a missing JSON file is skipped silently")

-- Running setup again replaces the config instead of stacking wrappers.
tr.setup({ roots = {}, files = { tmp .. "/broken.json" } })
assert(vim.secure.read(tmp .. "/trusted/repo/.nvim.lua") == "FALLBACK", "setup replaces the roots")
assert(#warnings == 1 and warnings[1]:find("broken.json", 1, true), "a broken JSON file warns")

vim.fn.delete(tmp, "rf")
print("ok")
