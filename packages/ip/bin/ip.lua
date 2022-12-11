local shell = require("shell")
local ip = require("ip")
local component = require("component")

local args, opts = shell.parse(...)

if opts.help then
  print([[Usage: ip [subcommand] [optiona]...
  addr :: displays configured addresses

  Shows the WIP configuration for all attached network cards.]])
  return 0
end

if args[1] == "addr" then
  local interfaces = ip.interfaces

  for modemId,_ in pairs(component.list("modem")) do
    local cfg = wip.getConfigForInterface(modemId)
    print("net " .. modemId, "wip " .. (cfg.addr or "N/A"))
  end
end