local wip = require("wip")
local shell = require("shell")
local component = require("component")
local computer = require("computer")

local args, opts = shell.parse(...)

if #args ~= 1 or opts.help then
  print([[Usage: ping [HOST]

  Sends a WIMP ping message to the specified host.
  ]])
  return 0
end

local srcHost = args[1] -- TODO
local host = args[1]

