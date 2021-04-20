local shell = require("shell")

local args, opts = shell.parse(...)

if opts.help then
  print([[Usage: pkgreload [PACKAGE]...
  
  Reloads the specified package(s).
  ]])
  return 0
end

for _,pkgname in ipairs(args) do
  package.loaded[pkgname] = nil
  require(pkgname)
end